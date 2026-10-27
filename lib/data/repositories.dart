import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'local_db.dart';
import 'models.dart';

class AuthRepository {
  AuthRepository(this.api, this.db);

  final ApiClient api;
  final LocalDb db;

  Future<AppUser> login(String identifier, String password) async {
    final res = await api.dio.post('/auth/login', data: {
      'identifier': identifier.trim(),
      'password': password,
    });
    return _persist(res.data as Map<String, dynamic>);
  }

  Future<AppUser> register({
    required String name,
    required String username,
    required String email,
    required String password,
    String? phone,
    String? roomNumber,
  }) async {
    final res = await api.dio.post('/auth/register', data: {
      'name': name.trim(),
      'username': username.trim(),
      'email': email.trim(),
      'password': password,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (roomNumber != null && roomNumber.trim().isNotEmpty)
        'roomNumber': roomNumber.trim(),
    });
    return _persist(res.data as Map<String, dynamic>);
  }

  Future<AppUser> _persist(Map<String, dynamic> data) async {
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    final token = data['token'] as String;
    api.token = token;
    await db.saveSession(token, user);
    return user;
  }

  /// Pulihkan sesi dari SQLite. Offline tetap masuk memakai sesi tersimpan.
  Future<AppUser?> restore() async {
    final session = await db.loadSession();
    if (session == null) return null;
    api.token = session.token;
    try {
      final res = await api.dio.get('/auth/me');
      final user = AppUser.fromJson(
        (res.data as Map<String, dynamic>)['user'] as Map<String, dynamic>,
      );
      await db.saveSession(session.token, user);
      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        return null;
      }
      return session.user; // offline / server mati
    }
  }

  Future<void> logout() async {
    api.token = null;
    await db.clearSession();
  }
}

class CartItem {
  const CartItem(this.service, this.quantity);
  final Service service;
  final double quantity;
}

class OrdersResult {
  const OrdersResult(this.orders, {required this.offline});
  final List<LaundryOrder> orders;
  final bool offline;
}

class OrderRepository {
  OrderRepository(this.api, this.db);

  final ApiClient api;
  final LocalDb db;
  static const _uuid = Uuid();
  static const _servicesKey = 'services_json';

  // ---------- Layanan ----------

  Future<List<Service>> fetchServices() async {
    try {
      final res = await api.dio.get('/services');
      final list = ((res.data as Map<String, dynamic>)['services'] as List)
          .cast<Map<String, dynamic>>();
      await db.putKv(_servicesKey, jsonEncode(list));
      return list.map(Service.fromJson).toList();
    } on DioException catch (e) {
      if (!isNetworkError(e)) rethrow;
      final cached = await db.getKv(_servicesKey);
      if (cached == null) rethrow;
      return (jsonDecode(cached) as List)
          .map((j) => Service.fromJson(j as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> saveService({
    String? id,
    required String name,
    String? description,
    required String unit,
    required int price,
    bool? active,
  }) async {
    final body = {
      'name': name,
      'description': description,
      'unit': unit,
      'price': price,
      if (active != null) 'active': active,
    };
    if (id == null) {
      await api.dio.post('/services', data: body);
    } else {
      await api.dio.put('/services/$id', data: body);
    }
  }

  Future<void> setServiceActive(String id, bool active) async {
    await api.dio.put('/services/$id', data: {'active': active});
  }

  // ---------- Pesanan ----------

  Future<OrdersResult> fetch(AppUser user) async {
    try {
      if (!user.isAdmin) await _syncPending(user);

      final res = await api.dio.get('/orders');
      final list = ((res.data as Map<String, dynamic>)['orders'] as List)
          .cast<Map<String, dynamic>>();
      await db.replaceCachedOrders(user.id, list);

      final orders = list.map((j) => LaundryOrder.fromJson(j)).toList();
      final pending = user.isAdmin ? <LaundryOrder>[] : await _pendingOrders(user.id);
      return OrdersResult([...pending, ...orders], offline: false);
    } on DioException catch (e) {
      if (!isNetworkError(e)) rethrow;
      final cached = await db.loadCachedOrders(user.id);
      final pending = user.isAdmin ? <LaundryOrder>[] : await _pendingOrders(user.id);
      return OrdersResult([...pending, ...cached], offline: true);
    }
  }

  Future<List<LaundryOrder>> _pendingOrders(String ownerId) async {
    final rows = await db.loadPending(ownerId);
    return rows
        .map((r) => LaundryOrder.fromJson(r.preview, synced: false))
        .toList()
        .reversed
        .toList();
  }

  /// Kirim antrean pesanan offline ke server. Idempotent berkat clientId.
  Future<void> _syncPending(AppUser user) async {
    final rows = await db.loadPending(user.id);
    for (final r in rows) {
      try {
        await api.dio.post('/orders', data: r.payload);
        await db.removePending(r.clientId);
      } on DioException catch (e) {
        if (isNetworkError(e)) return; // masih offline, coba lagi nanti
        final code = e.response?.statusCode;
        // 400 = payload tidak akan pernah valid (mis. layanan sudah dihapus).
        if (code == 400) {
          await db.removePending(r.clientId);
        } else {
          rethrow;
        }
      }
    }
  }

  /// Buat pesanan. Jika offline, simpan ke SQLite dan kirim saat online.
  Future<LaundryOrder> createOrder(
    AppUser user, {
    required List<CartItem> items,
    String? roomNumber,
    DateTime? pickupTime,
    String? instructions,
  }) async {
    final clientId = _uuid.v4();
    final payload = <String, dynamic>{
      'clientId': clientId,
      'roomNumber': roomNumber,
      'pickupTime': pickupTime?.toUtc().toIso8601String(),
      'specialInstructions': instructions,
      'items': [
        for (final i in items) {'serviceId': i.service.id, 'quantity': i.quantity},
      ],
    };

    try {
      final res = await api.dio.post('/orders', data: payload);
      return LaundryOrder.fromJson(
        (res.data as Map<String, dynamic>)['order'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (!isNetworkError(e)) rethrow;

      final preview = <String, dynamic>{
        'id': clientId,
        'clientId': clientId,
        'status': 'PENDING',
        'roomNumber': roomNumber,
        'pickupTime': pickupTime?.toUtc().toIso8601String(),
        'specialInstructions': instructions,
        'totalPrice': items.fold<int>(
          0,
          (s, i) => s + (i.service.price * i.quantity).round(),
        ),
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'items': [
          for (final i in items)
            {
              'serviceName': i.service.name,
              'unit': i.service.unit,
              'unitPrice': i.service.price,
              'quantity': i.quantity,
              'subtotal': (i.service.price * i.quantity).round(),
            },
        ],
      };
      await db.addPending(
        clientId: clientId,
        ownerId: user.id,
        payload: payload,
        preview: preview,
      );
      return LaundryOrder.fromJson(preview, synced: false);
    }
  }

  Future<void> updateStatus(String orderId, String status, {String? reason}) async {
    await api.dio.put('/orders/$orderId/status', data: {
      'status': status,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }
}
