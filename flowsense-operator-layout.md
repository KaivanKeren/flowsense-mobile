# FlowSense — Aplikasi Operator: Spesifikasi Layout

Untuk Claude Code. Pasangan dari `flowsense-warga-layout.md` (aplikasi warga), `2026-08-02-flowsense-mobile-flutter.md` (rencana teknis), dan `docs/api-contract.md`.

Flavor `operator` berbagi seluruh lapisan `core/`, `data/`, dan `domain/` dengan flavor `warga`. Yang berbeda hanya `features/` dan satu hal di lapisan data: header autentikasi.

---

## Referensi visual

Letakkan hasil ekspor Stitch di `assets/design/`.

| Berkas | Layar |
|---|---|
| `assets/design/operator-01-login.png` | Login |
| `assets/design/operator-02-dashboard.png` | Dashboard, ringkasan + peringatan + daftar simpang |
| `assets/design/operator-03-detail.png` | Detail simpang, kamera + lajur + riwayat 24 jam |
| `assets/design/operator-04-kesehatan.png` | Kesehatan connector |
| `assets/design/operator-05-kalibrasi.png` | Kalibrasi kapasitas lajur |
| `assets/design/operator-06-peringatan.png` | Riwayat peringatan |
| `assets/design/operator-07-akun.png` | Akun dan keluar |

**Baca gambarnya sebelum menulis layar.** Untuk tiap layar, buka berkas PNG-nya lebih dulu, lalu bangun dari gambar itu ditambah teks di bawah.

**Urutan kewenangan bila keduanya berbeda:**

1. Nilai token pada `lib/app/theme.dart` — selalu menang atas warna apa pun di gambar
2. Teks pada dokumen ini — menang atas label di gambar
3. Gambar — menang untuk proporsi, urutan, jarak, dan berat visual

Alasannya: Stitch menyisipkan bayangan, gradasi, dan tab tambahan meski dilarang, dan sering mengubah label. Yang benar-benar berharga dari gambarnya adalah tata letak, bukan detailnya.

**Yang tidak boleh diambil dari gambar sama sekali:** apa pun yang menyiratkan kendali lampu lalu lintas, tab kelima pada bilah bawah, tombol ekspor atau tambah pada layar bertabel, dan foto profil pada layar Akun. Bila muncul di ekspor, itu isian otomatis generator — abaikan.

**Kunci hasilnya dengan golden test.** Setelah satu layar dianggap selesai, buat `testWidgets` yang merender layar itu pada 360×800 dengan `FakeFlowSenseApi` dan bandingkan ke berkas emas di `test/goldens/`. Ini yang menjaga kemiripan bertahan setelah orang lain menyentuh kodenya; gambar referensi saja tidak menjaga apa pun.

---

## Perbedaan mendasar dari aplikasi warga

| | Warga | Operator |
|---|---|---|
| Autentikasi | Tidak ada | Wajib, email + sandi |
| Lebar konten | 448 px | 448 px |
| Kamera | Snapshot beranotasi | Stream langsung lewat proxy |
| Riwayat | 60 menit | 24 jam |
| Menulis data | Tidak pernah | Kalibrasi kapasitas, akui peringatan |

**Ponsel, 360×800, sama seperti aplikasi warga.** Gunakan `MaxWidth448`. Tidak ada tabel berkolom banyak — setiap baris data yang di desktop akan jadi tabel, di sini menjadi baris bertumpuk dua atau tiga tingkat: identitas di baris pertama, angka pendukung di baris kedua sebagai teks sekunder dipisah titik tengah.

Konsekuensinya harus diakui: operator kehilangan pandangan menyeluruh yang biasa didapat dari tabel lebar. Kompensasinya ada pada pengurutan — daftar selalu terurut terparah dulu, sehingga yang penting selalu berada di layar pertama tanpa perlu menggulir.

**Operator tetap tidak mengendalikan lampu lalu lintas.** Tidak ada mode manual, tidak ada pengaturan durasi hijau, tidak ada emergency preemption. Sistem tidak punya aktuator, dan menampilkan kontrol yang tidak tersambung ke apa pun adalah kebohongan antarmuka. Yang bisa ditulis operator hanya dua: kapasitas lajur dan pengakuan peringatan.

---

## Autentikasi

```
POST /v1/auth/login   → { token, operator: { id, nama, email } }
POST /v1/auth/logout
GET  /v1/auth/me
```

- Token disimpan di `flutter_secure_storage`, **bukan** `shared_preferences`.
- `HttpFlowSenseApi` menyuntikkan `Authorization: Bearer <token>` untuk flavor operator, menggantikan `X-FlowSense-Key`.
- **401 tidak pernah diulang.** Aturan ini sudah ada di Task 5; sekarang ia punya tujuan: 401 di tengah polling menghentikan repository, mengosongkan token, dan mengembalikan pengguna ke layar login. Satu widget test wajib: token kedaluwarsa saat polling berjalan → tidak ada permintaan lanjutan, status berubah jadi tidak terautentikasi.
- Tidak ada pendaftaran mandiri, tidak ada lupa sandi, tidak ada peran berlapis. Akun dibuat lewat seeder. Kalau ditanya penguji, jawabannya: akun operator diterbitkan oleh dinas, bukan didaftarkan sendiri.

---

## Peta rute

```
/login             LoginScreen
/                  DashboardScreen      daftar simpang + peringatan aktif
/simpang/:id       DetailScreen         kamera, lajur, riwayat 24 jam
/kesehatan         KesehatanScreen      status tiap connector
/kalibrasi/:id     KalibrasiScreen      kapasitas per lajur
/peringatan        PeringatanScreen     riwayat dan pengakuan
```

Navigasi: bilah bawah empat tab — **Dashboard · Kesehatan · Peringatan · Akun.** Sorotan kapsul abu `#EEF0ED` pada tab aktif, sama seperti aplikasi warga. Keluar berada di dalam Akun, bukan sebagai tab tersendiri.

Rute `/akun` ditambahkan: nama operator, email, dan tombol keluar. Ini satu-satunya tempat aplikasi operator punya sesuatu yang mirip profil, dan wajar karena di sini akun memang ada.

---

## 1. LoginScreen

Satu kolom penuh dengan margin 24 px, bukan kartu mengambang. Logo teks `FlowSense`, subjudul `Konsol operator`.

- Kolom email, kolom sandi dengan tombol perlihatkan, tombol `Masuk` selebar kartu.
- Galat ditampilkan sebagai satu baris merah di atas tombol, bukan snackbar — snackbar hilang sebelum sempat dibaca.
- Tombol memasuki keadaan memuat, bukan membuka dialog.
- Baris kecil di bawah: `Akun diterbitkan oleh dinas. Hubungi administrator bila lupa sandi.`

Untuk demo penjurian: sediakan akun demo dengan kredensial **sudah terisi** di kolom. Mengetik sandi di depan penguji sambil salah ketik dua kali adalah cara buruk memulai presentasi.

---

## 2. DashboardScreen

Satu kolom, urutan dari atas.

**Ringkasan** — empat angka dalam satu baris: macet, padat, lancar, tanpa data. Angka netral `#1A1D1C`, bukan berwarna; warna di layar ini hanya untuk pil status.

**Peringatan aktif** diletakkan di atas daftar simpang, bukan di samping. Di ponsel, yang butuh tindakan harus lebih dulu terlihat daripada yang butuh pemantauan. Kartu per peringatan: nama simpang, sejak kapan macet, tombol `Akui`. Setelah diakui, kartu berpindah ke bagian bawah dengan nama pengaku dan waktunya. Peringatan yang sudah diakui tidak hilang — riwayatnya adalah inti akuntabilitas. Bila tidak ada peringatan, tampilkan satu baris tenang `Tidak ada peringatan aktif`, bukan bagian kosong.

**Daftar simpang**, urut terparah dulu. Tiap baris dua tingkat: baris pertama nama simpang, pil status, dan titik kecil kesehatan connector di kanan; baris kedua teks sekunder `18 kendaraan · arah kota · 7 detik lalu`. Baris dengan connector mati diredupkan dan bertanda `Data basi`.

---

## 3. DetailScreen

Header: nama simpang, pil status, waktu perbarui, tombol `Kalibrasi`.

Urutan konten:

1. **Panel kamera**, rasio 16:9, stream langsung lewat proxy backend. Pemutar dibungkus `VideoPanel` dengan tiga keadaan eksplisit: memuat, berjalan, gagal. Keadaan gagal menampilkan `Stream terputus` dan tombol `Muat ulang` — jangan biarkan pemutar diam tanpa penjelasan. Deteksi buffering lebih dari 10 detik memicu muat ulang playlist otomatis, sekali, lalu menyerah ke keadaan gagal.
2. **Rincian per lajur** — sama seperti aplikasi warga, ditambah kolom kapasitas dan rasio dalam persen.
3. **Riwayat 24 jam** — batang per 15 menit, 96 titik. Di 360 px itu sekitar 3 px per batang, masih terbaca; 288 titik per 5 menit akan menjadi garis kabur dan tidak boleh dipakai di sini. Tinggi = jumlah kendaraan, warna = lajur terparah. Periode tanpa data digambar rata di dasar, tidak diinterpolasi. Mengetuk batang menampilkan pembacaan waktu itu di atas grafik.
4. **Catatan sumber** — URL kamera, waktu record terakhir, versi connector.

---

## 4. KesehatanScreen

Satu baris dua tingkat per connector. Baris pertama: nama kamera dan simpang, pil status di kanan (`Berjalan`, `Terputus`, `Berhenti`). Baris kedua sebagai teks sekunder: `record terakhir 16:42:07 · jeda 2,0 detik · 0 gagal/jam`.

Ini layar yang paling sering dibuka saat sesuatu terasa salah, dan satu-satunya tempat operator bisa membedakan "jalan memang sepi" dari "connector mati". Jangan gabungkan ke Dashboard.

---

## 5. KalibrasiScreen

Satu baris per lajur: nama lajur · kolom angka kapasitas · pratinjau level yang dihasilkan oleh hitungan saat ini.

Pratinjau itu penting — operator harus melihat akibat perubahannya sebelum menyimpan. Ubah kapasitas dari 12 ke 16, hitungan 9 berubah dari macet jadi padat, dan itu tampil seketika sebelum tombol `Simpan` ditekan.

- Tombol `Simpan` dan `Batal`. Tanpa simpan otomatis.
- Setelah simpan, tampilkan siapa dan kapan terakhir mengubah.
- Panduan satu baris: `Kapasitas adalah jumlah kendaraan yang memenuhi lajur saat berhenti total.`

---

## 6. PeringatanScreen

Daftar kartu, bukan tabel. Tiap kartu: waktu dan nama simpang di baris pertama dengan pil status di kanan; `macet 37 menit` di baris kedua; nama pengaku dan catatan di baris ketiga bila ada.

Penyaring sebagai satu baris chip yang bisa digeser mendatar: rentang waktu, simpang, status. Tanpa ekspor — di luar lingkup.

---

## Token dan gaya

Sama persis dengan aplikasi warga. Empat warna kepadatan tetap hanya untuk menyatakan kepadatan; jangan dipakai untuk tombol atau aksen di konsol ini, meski godaannya lebih besar karena layarnya lebih padat.

Perbedaan satu-satunya: baris data bertingkat dua, dengan tinggi minimum 56 px agar target sentuh tetap memenuhi 44 px. Ukuran isi tetap 13 px dan teks sekunder 11 px — jangan diturunkan demi memuat lebih banyak kolom.

---

## Yang sengaja tidak dibuat

- **Kendali lampu lalu lintas** dalam bentuk apa pun. Tidak ada aktuator.
- **Pendaftaran, lupa sandi, undangan, peran berlapis, OAuth.** Berhari-hari pekerjaan, nol poin penilaian.
- **Kelola GIS (tambah/edit/hapus perempatan) dari aplikasi.** Simpang dimasukkan lewat seeder; empat simpang tidak butuh CRUD.
- **Impor data dan ekspor laporan.** Di luar lingkup dua minggu.
- **Mode gelap.** Menggandakan pekerjaan pemeriksaan kontras.

---

## Kriteria selesai

- [ ] 401 mengeluarkan pengguna ke `/login` dan menghentikan polling — diuji lewat widget test
- [ ] Token tersimpan di `flutter_secure_storage`, bukan `shared_preferences`
- [ ] Tidak ada satu pun kontrol yang menulis ke lampu lalu lintas
- [ ] Kalibrasi menampilkan pratinjau level sebelum disimpan
- [ ] Pengakuan peringatan mencatat operator dan waktu, dan tidak menghapus baris
- [ ] Connector mati terbaca jelas di Dashboard dan Kesehatan, tidak tersamar sebagai lancar
- [ ] Stream gagal menampilkan pesan dan tombol muat ulang, bukan layar diam
- [ ] Seluruh isi terbungkus `MaxWidth448`; tidak ada tabel berkolom banyak dan tidak ada gulir mendatar
- [ ] Peringatan aktif berada di atas daftar simpang pada Dashboard
- [ ] Berjalan penuh dengan `FakeFlowSenseApi`, termasuk login palsu
