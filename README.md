# CatatKu

Aplikasi pencatatan keuangan Android berbasis Flutter dan SQLite.

## Isi
- Dashboard saldo, pemasukan, pengeluaran
- Grafik arus kas harian untuk bulan terpilih
- Tambah pemasukan dan pengeluaran
- Kategori transaksi dan tanggal
- Hapus transaksi dengan swipe ke kiri
- Penyimpanan lokal SQLite, tanpa login dan tanpa internet

## Build APK gratis dari HP
1. Buat repository GitHub bernama `catatku`.
2. Upload folder `lib`, file `pubspec.yaml`, dan folder `.github` ke root repository.
3. Buka tab Actions dan aktifkan Actions jika diminta.
4. Jalankan workflow `Build CatatKu APK` melalui tombol Run workflow.
5. Setelah selesai, buka run yang sukses, cari Artifacts, lalu download `CatatKu-APK`.
6. Ekstrak ZIP dan install `app-release.apk`.

Workflow membuat kerangka Android Flutter sementara di runner GitHub, menyalin source aplikasi, lalu membangun APK release. Tidak perlu memasang Flutter SDK di HP.

## Catatan
- Build pertama dapat memerlukan beberapa menit.
- SQLite menyimpan data di perangkat. Menghapus aplikasi dapat menghapus data lokal; buat backup manual sebelum uninstall jika data penting.
- GitHub Actions memiliki batas pemakaian gratis dan kebijakan yang dapat berubah.
