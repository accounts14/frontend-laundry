import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clay.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../providers.dart';

/// Admin: kelola katalog layanan & harga.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(servicesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(servicesProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Layanan',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              ClayCard(
                radius: 20,
                padding: const EdgeInsets.all(12),
                color: ClayColors.primary,
                onTap: () => _edit(context, ref, null),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
          async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(errorMessage(e)),
            data: (list) => Column(
              children: [
                for (final s in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClayCard(
                      onTap: () => _edit(context, ref, s),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name,
                                    style: Theme.of(context).textTheme.titleMedium),
                                Text('${rupiah(s.price)} / ${unitLabel(s.unit)}',
                                    style: const TextStyle(
                                        color: ClayColors.primary,
                                        fontWeight: FontWeight.w900)),
                                if (!s.active)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 6),
                                    child: ClayPill(
                                        label: 'Nonaktif',
                                        color: ClayColors.textSoft),
                                  ),
                              ],
                            ),
                          ),
                          Switch(
                            value: s.active,
                            onChanged: (v) async {
                              try {
                                await ref
                                    .read(orderRepoProvider)
                                    .setServiceActive(s.id, v);
                                ref.invalidate(servicesProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(errorMessage(e))));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Service? s) async {
    final name = TextEditingController(text: s?.name);
    final desc = TextEditingController(text: s?.description);
    final price = TextEditingController(text: s?.price.toString());
    var unit = s?.unit ?? 'KG';

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClayColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s == null ? 'Layanan baru' : 'Ubah layanan',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 18),
                ClayTextField(label: 'Nama layanan', controller: name),
                const SizedBox(height: 14),
                ClayTextField(label: 'Deskripsi (opsional)', controller: desc),
                const SizedBox(height: 14),
                ClayTextField(
                  label: 'Harga (Rp)',
                  controller: price,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'KG', label: Text('Per kg')),
                    ButtonSegment(value: 'PIECE', label: Text('Per potong')),
                  ],
                  selected: {unit},
                  onSelectionChanged: (v) => setSheet(() => unit = v.first),
                ),
                const SizedBox(height: 22),
                ClayButton(
                  label: 'Simpan',
                  icon: Icons.save_rounded,
                  onPressed: () async {
                    final p = int.tryParse(price.text.trim());
                    if (name.text.trim().length < 2 || p == null || p < 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Nama dan harga harus valid')));
                      return;
                    }
                    try {
                      await ref.read(orderRepoProvider).saveService(
                            id: s?.id,
                            name: name.text.trim(),
                            description:
                                desc.text.trim().isEmpty ? null : desc.text.trim(),
                            unit: unit,
                            price: p,
                          );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(errorMessage(e))));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    name.dispose();
    desc.dispose();
    price.dispose();
    if (saved == true) ref.invalidate(servicesProvider);
  }
}
