import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clay.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../providers.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _room = TextEditingController();
  final _notes = TextEditingController();
  final _pickupCtrl = TextEditingController();
  final Map<String, double> _qty = {}; // serviceId -> jumlah
  DateTime? _pickup;
  bool _saving = false;
  bool _roomFilled = false;

  @override
  void dispose() {
    _room.dispose();
    _notes.dispose();
    _pickupCtrl.dispose();
    super.dispose();
  }

  int _total(List<Service> services) {
    var sum = 0;
    for (final s in services) {
      final q = _qty[s.id] ?? 0;
      sum += (s.price * q).round();
    }
    return sum;
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _pickup ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickup ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _pickup = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _pickupCtrl.text = formatDateTime(_pickup!);
    });
  }

  Future<void> _submit(List<Service> services) async {
    final items = [
      for (final s in services)
        if ((_qty[s.id] ?? 0) > 0) CartItem(s, _qty[s.id]!),
    ];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu layanan')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = ref.read(authProvider).valueOrNull!;
      final order = await ref.read(orderRepoProvider).createOrder(
            user,
            items: items,
            roomNumber: _room.text.trim().isEmpty ? null : _room.text.trim(),
            pickupTime: _pickup,
            instructions: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      await ref.read(ordersProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(order.synced
            ? 'Pesanan terkirim. Menunggu konfirmasi admin.'
            : 'Offline: pesanan disimpan dan dikirim saat online.'),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(servicesProvider);

    if (!_roomFilled) {
      _room.text = ref.read(authProvider).valueOrNull?.roomNumber ?? '';
      _roomFilled = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Pesanan')),
      body: SafeArea(
        child: servicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorMessage(e), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ClayButton(
                    label: 'Coba lagi',
                    expanded: false,
                    onPressed: () => ref.invalidate(servicesProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (services) => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  children: [
                    Text('Pilih layanan',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    for (final s in services) _serviceTile(s),
                    const SizedBox(height: 10),
                    Text('Detail pengantaran',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    ClayTextField(
                      label: 'Nomor kamar',
                      icon: Icons.meeting_room_rounded,
                      controller: _room,
                    ),
                    const SizedBox(height: 14),
                    ClayTextField(
                      label: 'Waktu penjemputan (opsional)',
                      icon: Icons.schedule_rounded,
                      controller: _pickupCtrl,
                      readOnly: true,
                      onTap: _pickDateTime,
                    ),
                    const SizedBox(height: 14),
                    ClayTextField(
                      label: 'Instruksi khusus (opsional)',
                      icon: Icons.edit_note_rounded,
                      controller: _notes,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimasi total',
                              style: TextStyle(color: ClayColors.textSoft)),
                          Text(rupiah(_total(services)),
                              style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ClayButton(
                        label: 'Pesan',
                        icon: Icons.send_rounded,
                        loading: _saving,
                        onPressed: () => _submit(services),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceTile(Service s) {
    final q = _qty[s.id] ?? 0;
    final step = s.unit == 'KG' ? 0.5 : 1.0;

    void change(double delta) {
      setState(() {
        final next = (q + delta).clamp(0, 999).toDouble();
        if (next <= 0) {
          _qty.remove(s.id);
        } else {
          _qty[s.id] = next;
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClayCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                  if (s.description?.isNotEmpty ?? false)
                    Text(s.description!,
                        style: const TextStyle(
                            color: ClayColors.textSoft, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${rupiah(s.price)} / ${unitLabel(s.unit)}',
                      style: const TextStyle(
                          color: ClayColors.primary, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            _stepper(Icons.remove_rounded, q > 0 ? () => change(-step) : null),
            SizedBox(
              width: 46,
              child: Text(formatQty(q),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
            _stepper(Icons.add_rounded, () => change(step)),
          ],
        ),
      ),
    );
  }

  Widget _stepper(IconData icon, VoidCallback? onTap) => Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: ClayCard(
          radius: 16,
          padding: const EdgeInsets.all(8),
          onTap: onTap,
          child: Icon(icon, size: 20, color: ClayColors.primary),
        ),
      );
}
