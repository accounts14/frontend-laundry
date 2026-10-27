import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// SQLite lokal:
/// - user_session   : profil + token JWT
/// - cached_orders  : cache riwayat pesanan (offline-first)
/// - pending_orders : antrean pesanan yang dibuat saat offline
/// - kv             : cache kecil (daftar layanan)
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'hotel_laundry.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE user_session(
            id INTEGER PRIMARY KEY,
            token TEXT NOT NULL,
            user_json TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE cached_orders(
            id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            json TEXT NOT NULL,
            created_at TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE pending_orders(
            client_id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            preview TEXT NOT NULL,
            created_at TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE kv(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )''');
      },
    );
  }

  // ---- Sesi ----
  Future<void> saveSession(String token, AppUser user) async {
    final db = await _database;
    await db.insert(
      'user_session',
      {'id': 1, 'token': token, 'user_json': jsonEncode(user.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<({String token, AppUser user})?> loadSession() async {
    final db = await _database;
    final rows = await db.query('user_session', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      token: r['token'] as String,
      user: AppUser.fromJson(
        jsonDecode(r['user_json'] as String) as Map<String, dynamic>,
      ),
    );
  }

  /// Hapus sesi + cache pesanan. Antrean pending dipertahankan
  /// (terikat owner_id) supaya tidak hilang saat logout.
  Future<void> clearSession() async {
    final db = await _database;
    await db.delete('user_session');
    await db.delete('cached_orders');
  }

  // ---- Cache pesanan ----
  Future<void> replaceCachedOrders(
    String ownerId,
    List<Map<String, dynamic>> orders,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('cached_orders', where: 'owner_id = ?', whereArgs: [ownerId]);
      for (final o in orders) {
        await txn.insert('cached_orders', {
          'id': o['id'],
          'owner_id': ownerId,
          'json': jsonEncode(o),
          'created_at': o['createdAt'],
        });
      }
    });
  }

  Future<List<LaundryOrder>> loadCachedOrders(String ownerId) async {
    final db = await _database;
    final rows = await db.query(
      'cached_orders',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map((r) => LaundryOrder.fromJson(
              jsonDecode(r['json'] as String) as Map<String, dynamic>,
            ))
        .toList();
  }

  // ---- Antrean offline ----
  Future<void> addPending({
    required String clientId,
    required String ownerId,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> preview,
  }) async {
    final db = await _database;
    await db.insert(
      'pending_orders',
      {
        'client_id': clientId,
        'owner_id': ownerId,
        'payload': jsonEncode(payload),
        'preview': jsonEncode(preview),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<({String clientId, Map<String, dynamic> payload, Map<String, dynamic> preview})>>
      loadPending(String ownerId) async {
    final db = await _database;
    final rows = await db.query(
      'pending_orders',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at ASC',
    );
    return rows
        .map((r) => (
              clientId: r['client_id'] as String,
              payload: jsonDecode(r['payload'] as String) as Map<String, dynamic>,
              preview: jsonDecode(r['preview'] as String) as Map<String, dynamic>,
            ))
        .toList();
  }

  Future<void> removePending(String clientId) async {
    final db = await _database;
    await db.delete('pending_orders', where: 'client_id = ?', whereArgs: [clientId]);
  }

  // ---- Key-value ----
  Future<void> putKv(String key, String value) async {
    final db = await _database;
    await db.insert(
      'kv',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getKv(String key) async {
    final db = await _database;
    final rows = await db.query('kv', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }
}
