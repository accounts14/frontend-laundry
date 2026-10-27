class AppConfig {
  /// Emulator Android: 10.0.2.2 menunjuk ke localhost komputer.
  /// HP fisik / produksi: jalankan dengan
  ///   flutter run --dart-define=API_URL=http://192.168.x.x:3000
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://hotel-laundry-be.vercel.app',
  );

  /// Interval polling status pesanan.
  static const pollInterval = Duration(seconds: 15);
}
