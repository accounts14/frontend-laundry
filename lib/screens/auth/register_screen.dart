import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clay.dart';
import '../../data/api_client.dart';
import '../../providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _room = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _username, _email, _phone, _room, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).register(
            name: _name.text,
            username: _username.text,
            email: _email.text,
            password: _pass.text,
            phone: _phone.text,
            roomNumber: _room.text,
          );
      // AuthGate otomatis mengganti layar; tutup halaman daftar.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _form,
            child: Column(
              children: [
                ClayTextField(
                  label: 'Nama lengkap',
                  icon: Icons.badge_rounded,
                  controller: _name,
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Minimal 2 karakter'
                      : null,
                ),
                const SizedBox(height: 14),
                ClayTextField(
                  label: 'Username',
                  icon: Icons.alternate_email_rounded,
                  controller: _username,
                  validator: (v) {
                    if (v == null || v.trim().length < 3)
                      return 'Minimal 3 karakter';
                    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(v.trim())) {
                      return 'Hanya huruf, angka, _ dan .';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                ClayTextField(
                  label: 'Email',
                  icon: Icons.mail_rounded,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Email tidak valid'
                      : null,
                ),
                const SizedBox(height: 14),
                ClayTextField(
                  label: 'No. HP (opsional)',
                  icon: Icons.phone_rounded,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                ClayTextField(
                  label: 'Nomor kamar (opsional)',
                  icon: Icons.meeting_room_rounded,
                  controller: _room,
                ),
                const SizedBox(height: 14),
                ClayTextField(
                  label: 'Password',
                  icon: Icons.lock_rounded,
                  controller: _pass,
                  obscure: true,
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                ),
                const SizedBox(height: 26),
                ClayButton(
                  label: 'Daftar',
                  icon: Icons.person_add_alt_1_rounded,
                  loading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
