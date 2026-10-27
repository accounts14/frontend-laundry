class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
    this.phone,
    this.roomNumber,
  });

  final String id;
  final String name;
  final String username;
  final String email;
  final String role; // CUSTOMER | ADMIN
  final String? phone;
  final String? roomNumber;

  bool get isAdmin => role == 'ADMIN';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String,
        username: j['username'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        phone: j['phone'] as String?,
        roomNumber: j['roomNumber'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
        'role': role,
        'phone': phone,
        'roomNumber': roomNumber,
      };
}

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    this.description,
    this.active = true,
  });

  final String id;
  final String name;
  final String? description;
  final String unit; // KG | PIECE
  final int price;
  final bool active;

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        unit: j['unit'] as String,
        price: (j['price'] as num).toInt(),
        active: j['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'unit': unit,
        'price': price,
        'active': active,
      };
}

class OrderItem {
  const OrderItem({
    required this.serviceName,
    required this.unit,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  final String serviceName;
  final String unit;
  final int unitPrice;
  final double quantity;
  final int subtotal;

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        serviceName: j['serviceName'] as String,
        unit: j['unit'] as String,
        unitPrice: (j['unitPrice'] as num).toInt(),
        quantity: (j['quantity'] as num).toDouble(),
        subtotal: (j['subtotal'] as num).toInt(),
      );
}

class LaundryOrder {
  const LaundryOrder({
    required this.id,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    required this.items,
    this.clientId,
    this.roomNumber,
    this.pickupTime,
    this.specialInstructions,
    this.rejectReason,
    this.customerName,
    this.synced = true,
  });

  final String id;
  final String? clientId;
  final String status; // PENDING | ACCEPTED | REJECTED | PROCESSING | DONE
  final String? roomNumber;
  final DateTime? pickupTime;
  final String? specialInstructions;
  final String? rejectReason;
  final int totalPrice;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String? customerName;

  /// false = tersimpan lokal (SQLite) dan belum terkirim ke server.
  final bool synced;

  factory LaundryOrder.fromJson(Map<String, dynamic> j, {bool synced = true}) {
    final user = j['user'] as Map<String, dynamic>?;
    return LaundryOrder(
      id: j['id'] as String,
      clientId: j['clientId'] as String?,
      status: j['status'] as String,
      roomNumber: j['roomNumber'] as String?,
      pickupTime: j['pickupTime'] == null
          ? null
          : DateTime.parse(j['pickupTime'] as String),
      specialInstructions: j['specialInstructions'] as String?,
      rejectReason: j['rejectReason'] as String?,
      totalPrice: (j['totalPrice'] as num).toInt(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      items: ((j['items'] as List?) ?? [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      customerName: user?['name'] as String?,
      synced: synced,
    );
  }
}
