import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'theme.dart';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String rupiah(num value) => _rupiah.format(value);

String formatDateTime(DateTime d) =>
    DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(d.toLocal());

String formatQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();

String unitLabel(String unit) => unit == 'KG' ? 'kg' : 'potong';

String statusLabel(String status) {
  switch (status) {
    case 'PENDING':
      return 'Menunggu Konfirmasi';
    case 'ACCEPTED':
      return 'Diterima';
    case 'REJECTED':
      return 'Ditolak';
    case 'PROCESSING':
      return 'Sedang Diproses';
    case 'DONE':
      return 'Selesai';
    default:
      return status;
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'PENDING':
      return const Color(0xFFE59A1F);
    case 'ACCEPTED':
      return ClayColors.primary;
    case 'REJECTED':
      return const Color(0xFFE5675A);
    case 'PROCESSING':
      return ClayColors.lilac;
    case 'DONE':
      return const Color(0xFF2FAF8F);
    default:
      return ClayColors.textSoft;
  }
}

IconData statusIcon(String status) {
  switch (status) {
    case 'PENDING':
      return Icons.hourglass_top_rounded;
    case 'ACCEPTED':
      return Icons.check_circle_rounded;
    case 'REJECTED':
      return Icons.cancel_rounded;
    case 'PROCESSING':
      return Icons.local_laundry_service_rounded;
    case 'DONE':
      return Icons.verified_rounded;
    default:
      return Icons.circle;
  }
}
