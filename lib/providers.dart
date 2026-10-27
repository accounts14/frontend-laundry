import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'data/api_client.dart';
import 'data/local_db.dart';
import 'data/models.dart';
import 'data/repositories.dart';
import 'services/notification_service.dart';

final apiProvider = Provider<ApiClient>((ref) {
  final api = ApiClient();
  api.onUnauthorized = () => ref.read(authProvider.notifier).forceLogout();
  return api;
});

final authRepoProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiProvider), LocalDb.instance),
);

final orderRepoProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(apiProvider), LocalDb.instance),
);

// ---------------- Auth ----------------

class AuthNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() => ref.read(authRepoProvider).restore();

  // Sengaja tidak memakai AsyncLoading agar layar login tidak ter-reset;
  // error dilempar ke pemanggil untuk ditampilkan.
  Future<void> login(String identifier, String password) async {
    final user = await ref.read(authRepoProvider).login(identifier, password);
    state = AsyncData(user);
  }

  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
    String? roomNumber,
  }) async {
    final user = await ref.read(authRepoProvider).register(
          name: name,
          username: username,
          email: email,
          password: password,
          phone: phone,
          roomNumber: roomNumber,
        );
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await ref.read(authRepoProvider).logout();
    state = const AsyncData(null);
  }

  Future<void> forceLogout() => logout();
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

// ---------------- Layanan ----------------

final servicesProvider = FutureProvider.autoDispose<List<Service>>((ref) {
  ref.watch(authProvider);
  return ref.read(orderRepoProvider).fetchServices();
});

// ---------------- Pesanan (polling + notifikasi) ----------------

class OrdersState {
  const OrdersState(this.orders, {this.offline = false});
  final List<LaundryOrder> orders;
  final bool offline;
}

class OrdersNotifier extends AsyncNotifier<OrdersState> {
  Timer? _timer;
  final Map<String, String> _lastStatus = {};
  bool _first = true;

  @override
  Future<OrdersState> build() async {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) return const OrdersState([]);

    _first = true;
    _lastStatus.clear();
    _timer = Timer.periodic(
      AppConfig.pollInterval,
      (_) => refresh(),
    );
    ref.onDispose(() => _timer?.cancel());

    return _load(user);
  }

  Future<OrdersState> _load(AppUser user) async {
    final r = await ref.read(orderRepoProvider).fetch(user);
    _notifyChanges(user, r.orders);
    return OrdersState(r.orders, offline: r.offline);
  }

  /// [showLoading] true untuk pull-to-refresh; polling berjalan diam-diam.
  Future<void> refresh({bool showLoading = false}) async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;
    if (showLoading) {
      state = const AsyncLoading<OrdersState>().copyWithPrevious(state);
    }
    try {
      state = AsyncData(await _load(user));
    } catch (e, st) {
      // Polling yang gagal tidak menimpa data yang sudah tampil.
      if (showLoading || state.valueOrNull == null) {
        state = AsyncError(e, st);
      }
    }
  }

  void _notifyChanges(AppUser user, List<LaundryOrder> orders) {
    final notif = NotificationService.instance;

    if (!_first) {
      for (final o in orders.where((o) => o.synced)) {
        final previous = _lastStatus[o.id];
        if (user.isAdmin) {
          if (previous == null && o.status == 'PENDING') {
            notif.show(
              'Pesanan baru',
              '${o.customerName ?? 'Pelanggan'} membuat pesanan laundry'
                  '${o.roomNumber != null ? ' (kamar ${o.roomNumber})' : ''}.',
            );
          }
        } else if (previous != null && previous != o.status) {
          final msg = switch (o.status) {
            'ACCEPTED' => ('Pesanan diterima', 'Pesanan laundry Anda diterima admin.'),
            'REJECTED' => (
                'Pesanan ditolak',
                o.rejectReason?.isNotEmpty == true
                    ? 'Alasan: ${o.rejectReason}'
                    : 'Maaf, pesanan Anda ditolak admin.'
              ),
            'PROCESSING' => ('Laundry diproses', 'Pakaian Anda sedang dicuci.'),
            'DONE' => ('Laundry selesai', 'Pesanan Anda sudah selesai.'),
            _ => null,
          };
          if (msg != null) notif.show(msg.$1, msg.$2);
        }
      }
    }

    for (final o in orders.where((o) => o.synced)) {
      _lastStatus[o.id] = o.status;
    }
    _first = false;
  }
}

final ordersProvider =
    AsyncNotifierProvider<OrdersNotifier, OrdersState>(OrdersNotifier.new);
