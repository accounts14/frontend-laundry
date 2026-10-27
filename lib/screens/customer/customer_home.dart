import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clay.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../shared/order_widgets.dart';
import 'create_order_screen.dart';

class CustomerHome extends ConsumerStatefulWidget {
  const CustomerHome({super.key});

  @override
  ConsumerState<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends ConsumerState<CustomerHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: const [_Dashboard(), _History()],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Riwayat'),
        ],
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull!;
    final orders = ref.watch(ordersProvider);
    final data = orders.valueOrNull;
    final active = data?.orders
            .where((o) => !['DONE', 'REJECTED'].contains(o.status))
            .toList() ??
        [];

    return RefreshIndicator(
      onRefresh: () => ref.read(ordersProvider.notifier).refresh(showLoading: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Halo,', style: TextStyle(color: ClayColors.textSoft)),
                    Text(user.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              ClayCard(
                radius: 20,
                padding: const EdgeInsets.all(12),
                onTap: () => _confirmLogout(context, ref),
                child: const Icon(Icons.logout_rounded, color: ClayColors.text),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClayCard(
            color: ClayColors.primary,
            radius: 34,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_laundry_service_rounded,
                    color: Colors.white, size: 34),
                const SizedBox(height: 12),
                const Text('Cucian menumpuk?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                const Text('Pesan laundry langsung dari kamar Anda.',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ClayButton(
                  label: 'Buat Pesanan',
                  icon: Icons.add_rounded,
                  color: ClayColors.sun,
                  foreground: ClayColors.text,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('Pesanan aktif', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          if (data?.offline ?? false) const OfflineBanner(),
          if (orders.isLoading && data == null)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else if (orders.hasError && data == null)
            const EmptyState(icon: Icons.error_outline, text: 'Gagal memuat pesanan')
          else if (active.isEmpty)
            const EmptyState(
                icon: Icons.checkroom_rounded, text: 'Belum ada pesanan aktif')
          else
            for (final o in active)
              OrderCard(
                order: o,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ClayColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Keluar?'),
        content: const Text('Anda harus login lagi untuk memesan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) await ref.read(authProvider.notifier).logout();
  }
}

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final data = orders.valueOrNull;

    return RefreshIndicator(
      onRefresh: () => ref.read(ordersProvider.notifier).refresh(showLoading: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Riwayat Pesanan', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (data?.offline ?? false) const OfflineBanner(),
          if (orders.isLoading && data == null)
            const Center(child: CircularProgressIndicator())
          else if (data == null || data.orders.isEmpty)
            const EmptyState(icon: Icons.receipt_long_rounded, text: 'Belum ada pesanan')
          else
            for (final o in data.orders)
              OrderCard(
                order: o,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(order: o)),
                ),
              ),
        ],
      ),
    );
  }
}
