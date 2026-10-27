#!/usr/bin/env bash
# Jalankan SEKALI dari folder app/ setelah Flutter SDK terpasang.
# Membuat scaffolding Android dan menambahkan konfigurasi yang dibutuhkan.
set -euo pipefail

flutter create . --platforms=android --org com.hotellaundry --project-name hotel_laundry_care
flutter pub get

MANIFEST=android/app/src/main/AndroidManifest.xml

# 1) Izin internet + notifikasi (Android 13+)
if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application#' "$MANIFEST"
fi

# 2) Izinkan http:// (untuk dev ke server lokal). Hapus saat produksi (pakai https).
if ! grep -q "usesCleartextTraffic" "$MANIFEST"; then
  sed -i 's#<application#<application android:usesCleartextTraffic="true"#' "$MANIFEST"
fi

# 3) Nama aplikasi
sed -i 's#android:label="[^"]*"#android:label="Hotel Laundry Care"#' "$MANIFEST"

echo
echo "Selesai. Jika build gagal soal 'desugaring' (flutter_local_notifications),"
echo "lihat bagian Troubleshooting di README.md."
