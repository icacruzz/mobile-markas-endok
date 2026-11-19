# Markas Endog

Aplikasi Flutter untuk membantu operasional peternakan ayam petelur. Data operasional disimpan di Firebase; antarmuka dan menu utama berbahasa Indonesia.

## Fitur

- **Akun:** daftar, login, pemantauan status autentikasi, dan logout.
- **Beranda:** ringkasan produksi, stok pakan, pemasukan dan pengeluaran, grafik tren panen, serta riwayat terbaru.
- **Produksi/panen:** catat dan ubah hasil panen, cari dan filter catatan, lihat grafik, dan ekspor data ke Excel.
- **Pakan:** catat pembelian dan konsumsi, lihat stok dan perkiraan hari stok habis, grafik konsumsi, riwayat pembelian, serta lampirkan foto nota. Pembelian pakan juga dicatat sebagai pengeluaran di buku kas.
- **Buku kas:** catat dan ubah pemasukan/pengeluaran, lihat transaksi, dan ekspor laporan ke Excel atau PDF.
- **Profil dan notifikasi:** lihat profil/token perangkat dan menerima notifikasi Firebase Cloud Messaging.

## Tech stack

- **Flutter dan Dart** untuk aplikasi lintas platform; UI memakai Material 3.
- **Firebase Core** untuk inisialisasi Firebase, **Firebase Authentication** untuk akun, **Cloud Firestore** untuk data, dan **Firebase Cloud Messaging** untuk notifikasi.
- **fl_chart** untuk grafik; **Google Fonts** untuk tipografi.
- **image_picker** dan **image** untuk memilih/memproses gambar nota.
- **excel**, **pdf**, **printing**, dan **share_plus** untuk membuat serta membagikan ekspor.
- **intl** untuk format tanggal dan angka lokal.

## Jalankan

Pastikan Flutter SDK tersedia, dependensi terpasang (`flutter pub get`), dan konfigurasi Firebase untuk platform target sudah benar. Kemudian jalankan `flutter run`.
