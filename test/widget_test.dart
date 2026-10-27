import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hotel_laundry_care/core/clay.dart';
import 'package:hotel_laundry_care/core/format.dart';

// Catatan: HotelLaundryApp sengaja tidak di-pump di sini karena memakai
// SQLite dan notifikasi (plugin platform) yang tidak tersedia di flutter test.
void main() {
  test('format helper', () {
    expect(formatQty(2), '2');
    expect(formatQty(2.5), '2.5');
    expect(unitLabel('KG'), 'kg');
    expect(unitLabel('PIECE'), 'potong');
    expect(statusLabel('PENDING'), 'Menunggu Konfirmasi');
    expect(statusLabel('DONE'), 'Selesai');
  });

  testWidgets('ClayButton memanggil onPressed saat di-tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClayButton(label: 'Pesan', onPressed: () => taps++),
        ),
      ),
    );

    await tester.tap(find.text('Pesan'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('ClayButton nonaktif saat loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClayButton(
              label: 'Pesan', loading: true, onPressed: () => taps++),
        ),
      ),
    );

    await tester.tap(find.byType(ClayButton));
    await tester.pump();
    expect(taps, 0);
  });
}
