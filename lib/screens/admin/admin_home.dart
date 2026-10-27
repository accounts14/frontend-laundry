import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clay.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../providers.dart';
import '../shared/order_widgets.dart';
import 'services_screen.dart';

class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key});

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: const [_Incoming(), _Report(), ServicesScreen()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_rounded), label: 'Pesanan'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Laporan'),
          NavigationDestination(icon: Icon(Icons.sell_rounded), label: 'Layanan'),
        ],
      ),
    );
  }
}

Future<void> _logout(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ClayColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Keluar?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
      ],
    ),
  );
  if (ok == true) await ref.read(authProvider.notifier).logout();
}

void _open(BuildContext context, LaundryOrder o) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(order: o, adminMode: true),
      ),
    );

/// Dashboard: pesanan yang masih perlu ditangani, pending di paling atas.
class _Incoming extends ConsumerWidget {
  const _Incoming();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final data = orders.valueOrNull;
    final all = data?.orders ?? [];

    final pending = all.where((o) => o.status == 'PENDING').toList();
    final running =
        all.where((o) => ['ACCEPTED', 'PROCESSING'].contains(o.status)).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(ordersProvider.notifier).refresh(showLoading: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Dashboard Admin',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              ClayCard(
                radius: 20,
                padding: const EdgeInsets.all(12),
                onTap: () => _logout(context, ref),
                child: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                    label: 'Menunggu',
                    value: pending.length,
                    color: const Color(0xFFE59A1F)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Stat(
                    label: 'Berjalan',
                    value: running.length,
                    color: ClayColors.lilac),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (data?.offline ?? false) const OfflineBanner(),
          if (orders.isLoading && data == null)
            const Center(child: CircularProgressIndicator())
          else if (orders.hasError && data == null)
            const EmptyState(icon: Icons.error_outline, text: 'Gagal memuat pesanan')
          else ...[
            Text('Pesanan masuk', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            if (pending.isEmpty)
              const EmptyState(
                  icon: Icons.inbox_rounded, text: 'Tidak ada pesanan baru')
            else
              for (final o in pending)
                OrderCard(
                    order: o, showCustomer: true, onTap: () => _open(context, o)),
            if (running.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Sedang berjalan', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              for (final o in running)
                OrderCard(
                    order: o, showCustomer: true, onTap: () => _open(context, o)),
            ],
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClayCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w900, color: color)),
            Text(label, style: const TextStyle(color: ClayColors.textSoft)),
          ],
        ),
      );
}

/// Laporan sederhana: riwayat pesanan selesai atau ditolak.
class _Report extends ConsumerStatefulWidget {
  const _Report();

  @override
  ConsumerState<_Report> createState() => _ReportState();
}

class _ReportState extends ConsumerState<_Report> {
  String _filter = 'ALL'; // ALL | DONE | REJECTED

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final all = (orders.valueOrNull?.orders ?? [])
        .where((o) => o.status == 'DONE' || o.status == 'REJECTED')
        .toList();
    final list = _filter == 'ALL' ? all : all.where((o) => o.status == _filter).toList();
    final revenue = all
        .where((o) => o.status == 'DONE')
        .fold<int>(0, (s, o) => s + o.totalPrice);

    return RefreshIndicator(
      onRefresh: () => ref.read(ordersProvider.notifier).refresh(showLoading: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Laporan', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Selesai',
                  value: all.where((o) => o.status == 'DONE').length,
                  color: const Color(0xFF2FAF8F),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Stat(
                  label: 'Ditolak',
                  value: all.where((o) => o.status == 'REJECTED').length,
                  color: const Color(0xFFE5675A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClayCard(
            child: Row(
              children: [
                const Expanded(
                  child: Text('Total pendapatan (selesai)',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                Text(_rp(revenue),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            children: [
              for (final f in const [
                ('ALL', 'Semua'),
                ('DONE', 'Selesai'),
                ('REJECTED', 'Ditolak'),
              ])
                ChoiceChip(
                  label: Text(f.$2),
                  selected: _filter == f.$1,
                  onSelected: (_) => setState(() => _filter = f.$1),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (list.isEmpty)
            const EmptyState(icon: Icons.bar_chart_rounded, text: 'Belum ada data')
          else
            for (final o in list)
              OrderCard(
                  order: o, showCustomer: true, onTap: () => _open(context, o)),
        ],
      ),
    );
  }

  String _rp(int v) {
    final s = v.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    return 'Rp $s';
  }
}
