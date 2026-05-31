# Frontend Black-Box Testing

Dokumen ini berisi skenario black-box untuk menguji aplikasi Flutter dari sisi pengguna. Fokus pengujian adalah input, output, navigasi, state UI, dan pesan error tanpa melihat implementasi internal.

## Scope

Area yang diuji:

- Autentikasi email/password, Google Sign-In, register, reset password, dan logout.
- Startup session berdasarkan token tersimpan.
- Dashboard daftar kandang.
- QR/manual MAC claim device.
- BLE setup WiFi ESP32.
- Detail kandang, sensor terbaru, indikator cahaya, dan kontrol relay Lite.
- Kelola akses operator/viewer.
- Riwayat sensor dan aktivitas alert.
- Profile, unclaim kandang, hapus akun.
- Kondisi offline, maintenance, permission denied, rate limit, dan network error.

## Test Data

Siapkan data berikut di backend/Firebase staging:

| Data | Kebutuhan |
| --- | --- |
| Akun `admin` aktif | Punya minimal satu device claimed |
| Akun `operator` aktif | Di-assign ke satu device |
| Akun `viewer` aktif | Di-assign ke satu device |
| Akun `user` aktif | Belum punya akses device |
| Akun nonaktif | Untuk validasi forbidden/deactivated account |
| Device unclaimed | MAC valid untuk QR/manual claim |
| Device claimed | MAC valid tetapi sudah dimiliki user lain |
| Device online | Punya heartbeat dan sensor log terbaru |
| Device offline | Tidak punya heartbeat dalam 120 detik |

Gunakan backend staging dengan `.env`:

```env
BASE_URL=https://pcb.my.id
```

## Environment Matrix

| Target | Minimal coverage |
| --- | --- |
| Android physical device | Login, scan camera, BLE setup, device control |
| Android emulator | Login, navigation, list/detail/history/profile |
| Web/debug target | Smoke test UI non-native features only |
| Offline mode | Turn off internet during active session |

## Test Cases

### Authentication

| ID | Scenario | Steps | Expected result |
| --- | --- | --- | --- |
| AUTH-01 | Login form kosong | Buka app, tap `Masuk` tanpa email/password | Snackbar/error: email dan password tidak boleh kosong |
| AUTH-02 | Login email/password valid | Isi kredensial valid, tap `Masuk` | Masuk ke `HomeScreen`, tab pertama menampilkan `Daftar Kandang` |
| AUTH-03 | Login kredensial salah | Isi password salah, tap `Masuk` | Error login dari Firebase tampil, tetap di login |
| AUTH-04 | Login Google valid | Tap `Masuk dengan Google`, pilih akun valid | Token backend tersimpan dan app masuk ke dashboard |
| AUTH-05 | Login akun nonaktif | Login dengan akun yang dinonaktifkan backend | Dialog `Akun Dinonaktifkan`, tidak masuk dashboard |
| AUTH-06 | Reset password email kosong | Tap reset password, kosongkan email, tap `Kirim Link` | Error email kosong tampil |
| AUTH-07 | Reset password valid | Masukkan email terdaftar, tap `Kirim Link` | Snackbar link reset berhasil dikirim |
| AUTH-08 | Register valid | Buka register, isi data valid, submit | Akun dibuat, token backend ditukar, masuk dashboard |
| AUTH-09 | Startup dengan token valid | Login, tutup app, buka lagi | App langsung masuk `HomeScreen` |
| AUTH-10 | Startup tanpa token | Clear app data atau logout, buka app | App menampilkan `LoginPage` |

### Dashboard & Navigation

| ID | Scenario | Steps | Expected result |
| --- | --- | --- | --- |
| NAV-01 | Tab dashboard awal | Login sebagai admin | Tab 0 aktif, header greeting tampil, daftar kandang dimuat |
| NAV-02 | Bottom navigation | Tap tab BLE, Scan, Riwayat, Profile | Masing-masing halaman tampil tanpa crash |
| NAV-03 | Notifikasi kosong | Login dengan device tanpa alert | Bottom sheet notifikasi menampilkan kondisi aman |
| NAV-04 | Notifikasi alert | Login dengan device memiliki alert | Badge jumlah alert tampil, bottom sheet menampilkan alert |
| NAV-05 | Device list kosong | Login sebagai `user` tanpa akses | Empty state daftar kandang tampil dengan CTA scan |
| NAV-06 | Pagination daftar device | Gunakan akun dengan >20 device, tap next/previous | Halaman berubah dan daftar sesuai page |
| NAV-07 | Pull to refresh | Tarik daftar kandang ke bawah | Data direfresh tanpa duplikasi |
| NAV-08 | Buka detail device | Tap kartu device | Detail kandang terbuka dan tombol back kembali ke daftar |

### Device Detail & Control

| ID | Scenario | Steps | Expected result |
| --- | --- | --- | --- |
| DEV-01 | Sensor terbaru tampil | Buka detail device dengan log | Suhu, kelembapan, amonia, dan cahaya tampil |
| DEV-02 | Tidak ada log sensor | Buka detail device tanpa log | Placeholder `--`/loading berhenti, app tidak crash |
| DEV-03 | Status suhu normal | Gunakan log suhu 25-30 C | Status suhu `Normal` |
| DEV-04 | Status suhu bahaya | Gunakan log suhu <20 atau >35 C | Status suhu `Bahaya` |
| DEV-05 | Indikator cahaya terang | Log `light_level = 1` | Chip cahaya menampilkan `Terang` |
| DEV-06 | Indikator cahaya gelap | Log `light_level = 0` | Chip cahaya menampilkan `Gelap` |
| DEV-07 | Kontrol lampu berhasil | Toggle `Lampu` ON/OFF sebagai admin/operator | Switch berubah, loading per-switch tampil, snackbar sukses |
| DEV-08 | Kontrol pompa berhasil | Toggle `Pompa` ON/OFF sebagai admin/operator | Switch berubah, loading per-switch tampil, snackbar sukses |
| DEV-09 | Viewer mencoba kontrol | Login viewer, toggle komponen | Error akses ditolak, switch rollback |
| DEV-10 | Network error saat kontrol | Matikan internet lalu toggle | Error jaringan tampil, switch rollback, retry tersedia bila ditampilkan |
| DEV-11 | Kelola akses owner | Login sebagai owner device | Tombol `Kelola Akses` tampil di detail |
| DEV-12 | Kelola akses non-owner | Login operator/viewer | Tombol `Kelola Akses` tidak tampil |

### Claim Device

| ID | Scenario | Steps | Expected result |
| --- | --- | --- | --- |
| CLAIM-01 | QR valid dan device unclaimed | Scan QR berisi MAC valid, isi nama, simpan | Loading claim tampil, dialog sukses muncul |
| CLAIM-02 | QR format invalid | Scan QR bukan MAC valid | Dialog error format invalid, scanner bisa lanjut |
| CLAIM-03 | Manual MAC valid | Buka input manual, isi MAC unclaimed, isi nama | Device berhasil diklaim |
| CLAIM-04 | Nama kandang kosong | Scan/manual MAC valid, kosongkan nama | User tetap diminta mengisi nama atau claim dibatalkan |
| CLAIM-05 | Device sudah diklaim | Scan MAC claimed | Dialog `Device Sudah Diklaim` |
| CLAIM-06 | MAC tidak terdaftar | Scan MAC valid tetapi tidak ada di backend | Dialog `Device Tidak Ditemukan` |
| CLAIM-07 | Role tidak cukup | Login `user`, scan MAC unclaimed | Dialog akses ditolak |
| CLAIM-08 | Rate limit claim | Claim berulang melebihi limit | Snackbar/peringatan rate limit tampil |
| CLAIM-09 | Network error claim | Matikan internet saat claim | Dialog network error dengan opsi coba lagi |

### BLE WiFi Setup

| ID | Scenario | Steps | Expected result |
| --- | --- | --- | --- |
| BLE-01 | Permission ditolak | Tolak permission Bluetooth/lokasi | Snackbar izin ditolak |
| BLE-02 | Scan tidak menemukan device | Buka halaman BLE tanpa ESP32 dekat | Empty state `Tidak ada kandang terdekat` |
| BLE-03 | Device ditemukan | Nyalakan ESP32 provisioning, refresh scan | Nama/MAC device tampil dengan tombol `Setup` |
| BLE-04 | SSID kosong | Tap setup, kosongkan SSID, kirim | Snackbar SSID tidak boleh kosong |
| BLE-05 | Kirim WiFi valid | Isi SSID/password valid, kirim | Snackbar konfigurasi terkirim dan ESP32 restart |
| BLE-06 | Gagal koneksi BLE | Matikan ESP32 saat connect | Snackbar gagal terhubung |

### History

| ID | Scenario | Steps | Expected result |
| --- | --- | --- | --- |
| HIST-01 | Data suhu | Buka tab Riwayat, pilih `Suhu` | Tabel waktu/nilai/status tampil |
| HIST-02 | Data kelembapan | Pilih `Kelembapan` | Tabel kelembapan tampil |
| HIST-03 | Data amonia | Pilih `Amonia` | Tabel amonia tampil |
| HIST-04 | Aktivitas alert kosong | Pilih `Aktivitas` tanpa alert | Pesan kandang aman tampil |
| HIST-05 | Aktivitas alert ada | Pilih `Aktivitas` dengan alert | Daftar peringatan sensor tampil |
| HIST-06 | Refresh manual | Tap icon refresh | Data dimuat ulang tanpa crash |

### Profile & Account

| ID | Scenario | Steps | Expected result |
| --- | --- | --- | --- |
| PROF-01 | Profile tampil | Buka tab Profile | Nama, email, dan daftar kandang tampil |
| PROF-02 | Reset password dari profile | Tap aksi ganti password | Snackbar link dikirim atau error Firebase tampil |
| PROF-03 | Unclaim kandang | Tap lepas kandang dan konfirmasi | Kandang hilang dari daftar profile/dashboard |
| PROF-04 | Batal unclaim | Tap lepas kandang lalu batal | Tidak ada perubahan data |
| PROF-05 | Logout | Tap logout/keluar | Token lokal bersih dan kembali ke login |
| PROF-06 | Hapus akun batal | Tap hapus akun lalu batal | Akun tetap aktif |
| PROF-07 | Hapus akun konfirmasi | Konfirmasi hapus akun | Akun lokal dihapus, logout ke login |

### Resilience

| ID | Scenario | Steps | Expected result |
| --- | --- | --- | --- |
| RES-01 | Offline banner | Matikan internet saat app aktif | Banner offline tampil |
| RES-02 | Internet kembali | Nyalakan internet | Banner offline hilang |
| RES-03 | JWT expired | Pakai token expired lalu buka endpoint protected | App logout otomatis ke login |
| RES-04 | Backend maintenance | Backend mengembalikan 503 | Maintenance screen tampil |
| RES-05 | API 500 | Simulasikan server error | Pesan error umum tampil, app tidak crash |
| RES-06 | Refresh saat error | Trigger network/server error lalu retry | UI mencoba ulang request |

## Regression Checklist

Jalankan checklist ini sebelum rilis:

- Login email/password dan Google.
- Dashboard menampilkan device list untuk admin dan empty state untuk user.
- Scan/manual claim berhasil untuk device unclaimed.
- Detail device menampilkan sensor dan hanya toggle `Lampu`/`Pompa`.
- Viewer tidak bisa kontrol relay.
- Owner bisa membuka `Kelola Akses`.
- History menampilkan log dan alert.
- BLE setup bisa scan dan mengirim WiFi ke ESP32.
- Logout selalu kembali ke login.
- Offline, 401, 403, 429, 500, dan 503 punya feedback UI.

## Automation Notes

Prioritaskan automated widget/integration test untuk flow yang tidak memerlukan hardware:

- Login form validation.
- Route/tab navigation.
- Device list empty/loading/error states dengan mocked API.
- Device detail sensor rendering.
- Toggle rollback saat API gagal.
- History empty and populated states.
- Profile logout flow.

Flow yang membutuhkan kamera, Google Sign-In native, Firebase real account, BLE, dan physical ESP32 sebaiknya tetap masuk manual QA atau end-to-end test di perangkat fisik.
