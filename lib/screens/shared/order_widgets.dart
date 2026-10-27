import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clay.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../providers.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.showCustomer = false, this.onTap});

  final LaundryOrder order;
  final bool showCustomer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(order.status);
    final summary = order.items
        .map((i) => '${i.serviceName} ${formatQty(i.quantity)} ${unitLabel(i.unit)}')
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: ClayCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(statusIcon(order.status), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          showCustomer
                              ? (order.customerName ?? 'Pelanggan')
                              : 'Pesanan #${order.id.substring(0, 6).toUpperCase()}',
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(rupiah(order.totalPrice),
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ClayColors.textSoft)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ClayPill(label: statusLabel(order.status), color: color),
                      if (!order.synced)
                        const ClayPill(
                          label: 'Belum terkirim',
                          color: Color(0xFFE59A1F),
                        ),
                      Text(formatDateTime(order.createdAt),
                          style: const TextStyle(
                              fontSize: 12, color: ClayColors.textSoft)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClayCard(
        inverted: true,
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: const Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: Color(0xFFE59A1F)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mode offline: menampilkan data tersimpan.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 64, color: ClayColors.shadowDark),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: ClayColors.textSoft)),
        ],
      ),
    );
  }
}

/// Halaman detail pesanan. Admin mendapat tombol aksi sesuai status.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.order, this.adminMode = false});

  final LaundryOrder order;
  final bool adminMode;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;

  Future<void> _change(String status, {String? reason}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(orderRepoProvider)
          .updateStatus(widget.order.id, status, reason: reason);
      await ref.read(ordersProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ClayColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Tolak pesanan'),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Alasan singkat (opsional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Tolak',
                style: TextStyle(color: Color(0xFFE5675A), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (reason != null) await _change('REJECTED', reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final color = statusColor(o.status);

    final actions = <Widget>[];
    if (widget.adminMode && o.synced) {
      switch (o.status) {
        case 'PENDING':
          actions.addAll([
            Expanded(
              child: ClayButton(
                label: 'Tolak',
                icon: Icons.close_rounded,
                color: const Color(0xFFE5675A),
                loading: _busy,
                onPressed: _reject,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ClayButton(
                label: 'Terima',
                icon: Icons.check_rounded,
                color: const Color(0xFF2FAF8F),
                loading: _busy,
                onPressed: () => _change('ACCEPTED'),
              ),
            ),
          ]);
        case 'ACCEPTED':
          actions.add(Expanded(
            child: ClayButton(
              label: 'Mulai Proses',
              icon: Icons.local_laundry_service_rounded,
              color: ClayColors.lilac,
              loading: _busy,
              onPressed: () => _change('PROCESSING'),
            ),
          ));
        case 'PROCESSING':
          actions.add(Expanded(
            child: ClayButton(
              label: 'Tandai Selesai',
              icon: Icons.verified_rounded,
              color: const Color(0xFF2FAF8F),
              loading: _busy,
              onPressed: () => _change('DONE'),
            ),
          ));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Pesanan #${o.id.substring(0, 6).toUpperCase()}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            ClayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon(o.status), color: color, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(statusLabel(o.status),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: color)),
                      ),
                    ],
                  ),
                  if (o.status == 'REJECTED' &&
                      (o.rejectReason?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 10),
                    Text('Alasan: ${o.rejectReason}'),
                  ],
                  if (!o.synced) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Pesanan tersimpan di perangkat dan akan dikirim saat online.',
                      style: TextStyle(color: ClayColors.textSoft),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            ClayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (o.customerName != null) _info('Pelanggan', o.customerName!),
                  if (o.roomNumber?.isNotEmpty ?? false) _info('Kamar', o.roomNumber!),
                  if (o.pickupTime != null)
                    _info('Waktu jemput', formatDateTime(o.pickupTime!)),
                  _info('Dibuat', formatDateTime(o.createdAt)),
                  if (o.specialInstructions?.isNotEmpty ?? false)
                    _info('Instruksi', o.specialInstructions!),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ClayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rincian', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  for (final i in o.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${i.serviceName}\n${formatQty(i.quantity)} ${unitLabel(i.unit)} × ${rupiah(i.unitPrice)}',
                            ),
                          ),
                          Text(rupiah(i.subtotal),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Total',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                      Text(rupiah(o.totalPrice),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: actions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(color: ClayColors.textSoft)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}
