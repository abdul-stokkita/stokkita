STOKKITA ONLINE — Paket aplikasi web
====================================

PAKET INI BERISI
- index.html: aplikasi web responsif untuk HP dan desktop.
- supabase_setup.sql: skema database, autentikasi profil, role, Row Level Security (RLS), dan fungsi transaksi stok atomik.
- README.txt: panduan instalasi dan publikasi.

FITUR
- Login email + kata sandi melalui Supabase Auth.
- Database online bersama, dapat diakses dari perangkat berbeda.
- Dashboard: jenis barang, total stok, barang masuk/keluar bulan ini.
- Data barang: kode otomatis, nama, kategori, satuan, stok minimum.
- Transaksi barang masuk/keluar dengan tanggal dan catatan.
- Pembaruan stok dan pencatatan riwayat berlangsung atomik di database.
- Barang keluar melebihi stok akan ditolak.
- Peringatan stok menipis/habis.
- Filter dan ekspor CSV yang dapat dibuka di Excel.
- Role: admin (kelola master barang dan role), petugas (transaksi), pimpinan (baca).

CARA MEMASANG DATABASE ONLINE
1. Buat akun di Supabase: https://supabase.com
2. Buat proyek baru dan simpan password database di tempat aman.
3. Masuk ke SQL Editor pada proyek Supabase.
4. Buka file supabase_setup.sql, salin seluruh isinya, lalu jalankan.
5. Buka Project Settings > API (atau Connect) dan salin Project URL serta publishable key/anon key.
   Jangan pernah menggunakan service_role key pada aplikasi web.
6. Publikasikan folder ini sebagai situs statis (langkah publikasi di bawah).
7. Buka URL situs. Pada halaman awal, masukkan Project URL dan publishable/anon key.
   Konfigurasi tersimpan di browser perangkat tersebut. Pengguna lain memasukkannya sekali di perangkat mereka.
8. Buat akun pertama lewat Supabase Dashboard > Authentication > Users > Add user
   (atau aktifkan sign-up sesuai kebijakan organisasi).
9. Salin UUID akun pertama dari Authentication > Users.
10. Di SQL Editor jalankan:
    update public.profiles set role='admin', display_name='Administrator'
    where id='GANTI-DENGAN-UUID-AKUN';
11. Login melalui URL situs. Buat akun lain dari Authentication dan atur role:
    admin / petugas / pimpinan melalui SQL Editor.
    Role akun baru otomatis 'pimpinan' (read-only) sampai diubah admin.

CARA PUBLIKASI KE WEB (contoh GitHub Pages)
1. Buat akun di https://github.com lalu buat repository baru bernama stok-kita.
2. Unggah index.html ke root repository (supabase_setup.sql dan README opsional).
3. Di repository buka Settings > Pages.
4. Pada Build and deployment pilih Deploy from a branch, branch main, folder /(root), lalu Save.
5. Tunggu hingga GitHub menampilkan URL situs Pages. Buka URL itu di HP.
   Alternatif: hosting statis seperti Netlify atau Vercel juga dapat digunakan.
6. Jika URL situs berubah, konfigurasi Supabase tetap harus dimasukkan pada browser baru.

CATATAN KEAMANAN DAN OPERASIONAL
- File HTML hanya memuat Project URL dan publishable/anon key. Itu memang untuk frontend publik;
  keamanan data bergantung pada RLS dan fungsi database di SQL.
- Jangan pernah mempublikasikan service_role key atau password database.
- Batasi pembuatan akun berdasarkan kebijakan organisasi; bila sign-up publik aktif, siapa pun mungkin dapat mendaftar.
- Default role akun baru adalah pimpinan (hanya baca). Admin harus menetapkan role.
- Untuk operasional perusahaan, aktifkan MFA bila tersedia, gunakan kata sandi kuat, dan siapkan prosedur backup.
- Ekspor CSV secara berkala sebagai salinan tambahan.
- Aplikasi menampilkan maksimal 1.000 transaksi terbaru di layar; laporan CSV mengekspor data yang telah dimuat aplikasi.
- Uji dahulu dengan data contoh terbatas sebelum digunakan untuk stok nyata.
- Jika nama kolom/tabel diubah, frontend dan SQL perlu disesuaikan.

TROUBLESHOOTING
- "Akun belum memiliki profil": periksa trigger on_auth_user_created dan tabel profiles.
- "permission denied" atau gagal baca: pastikan seluruh SQL telah dijalankan dan akun sudah login.
- Role petugas tidak bisa menambah master barang: sesuai desain, hanya admin yang mengelola master barang.
- Login tidak dikenal: akun harus sudah dibuat di Supabase Authentication.

Paket ini adalah starter project yang siap dikonfigurasi dan dipublikasikan. File belum di-host oleh pembuat;
URL online baru tersedia setelah Anda melakukan langkah hosting dan menghubungkan proyek Supabase.
